# Manage the state which is shared with all clients
events = require 'eventemitter2'
async = require 'async'
_ = require 'underscore'
redis = require 'redis'
level = require 'level'
mysqldb = require 'mysql'

db = level './storage', {}, (err) ->
  throw err  if err
  if true
    console.log 'db opened', db.db.getProperty 'leveldb.stats'
    db.db.approximateSize ' ', '~', (err, size) ->
      throw err  if err
      console.log 'storage size ~ %d bytes', size

mdb = mysqldb.createConnection(
  host: 'localhost'
  user: 'sensors'
  password: 'sensors'
  database: 'sensors')
mdb.connect()

dbo = null

# set up the central data models used by each client
models =
  pkg: require '../package'
  local: require '../local'
  process: {}

# process info is useful in the client, but not all of it can be serialised
for k,v of process
  unless k in ['stdin', 'stdout', 'stderr', 'mainModule']
    unless typeof v is 'function'
      models.process[k] = v

# fetch and store implement a simple persistent and sharable key-value store
# "fetch" returns everything, "store" saves & propagates keyed object changes
# if the object has no "id", a new one will be assigned
# if the object has no "key", the old copy will be deleted

module.exports = state = new events.EventEmitter2(wildcard: true)
module.exports.db = db
module.exports.mdb = mdb

#state.onAny (args...) ->
#  console.info '>', @event, args...

# make sure this object has an id, issue a new one via redis if needed
# TODO: could avoid async with a scan for highest ID on node.js startup
setId = (name, obj, cb) ->
  if obj.id
    # noting to do
    cb obj.id
  else if obj.key?
    dbo.hget "#{name}:ids", obj.key, (err, id)->
      throw err  if err
      if id
        # there is an existing entry with this key, use it
        cb obj.id = id
      else
        dbo.hincrby 'ids', name, 1, (err, id) ->
          throw err  if err
          # issue and assign a new id
          cb obj.id = id

state.models = models

state.fetch = (cb) ->
  cb models

state.store = (name, obj, cb) ->
  setId name, obj, (id) ->
    collection = models[name] ? {}
    oldObj = collection[id]
    if obj is oldObj
      console.info 'store same?',name,obj.key
    unless obj is oldObj # TODO: is this comparison useful?
      key = obj.key
      if key?
        collection[id] = obj
        state.emit "set.#{name}", obj, oldObj
      else if oldObj?
        delete collection[id]
        state.emit "set.#{name}", null, oldObj
        key = oldObj.key
      else
        return
      models[name] = collection
      state.emit 'publish', name, obj, oldObj
    cb?()

state.reset = (name) ->
  for k,v of models[name]
    state.store name, { id: k }

state.setupStorage = (collections, config, cb) ->
  dbo = redis.createClient config.port, config.host, config

  state.on 'publish', (name, obj) ->
    if obj.key?
      dbo.hset name, obj.id, JSON.stringify(obj)
      dbo.hset "#{name}:ids", obj.key, obj.id
    else
      # key is gone, need to fetch original to recover it
      dbo.hget name, obj.id, (err, res) ->
        throw err  if err
        obj = JSON.parse res
        dbo.hdel name, obj.id
        dbo.hdel "#{name}:ids", obj.key

  dbo.select config.db, (err) ->
    throw err  if err
    async.eachSeries collections, (name, done) ->
      dbo.hgetall name, (err, ids) ->
        throw err  if err
        for k,v of ids
          state.store name, JSON.parse(v)
        done()
    , cb # called once all model collections have been restored
