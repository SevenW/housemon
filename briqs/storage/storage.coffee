state = require '../../server/state'
level = require 'level'

db = state.db

archiveValue = (time, param, value) ->
  dbkey = "reading~#{param}~#{time}"
  #console.log dbkey
  db.put dbkey, value, (err) ->
    throw err  if err

storeValue = (obj, oldObj) ->
  if obj? #therwise error on resetStatus
    archiveValue obj.time, obj.key, obj.origval

module.exports = class
  constructor: ->
    state.on 'set.status', storeValue
    state.on 'reprocess.status', archiveValue

  destroy: ->
    state.off 'set.status', storeValue
    state.off 'reprocess.status', archiveValue

  @rawRange: (key, from, to, cb) ->
    now = Date.now()
    from += now  if from < 0
    to += now  if to <= 0
    prefix = "reading~#{key}~"
    results = []
    s = db.createReadStream start: prefix + from, end: prefix + to
    s.on 'data', (data) ->
      results.push +data.value
      results.push +data.key.substr prefix.length
    s.on 'error', (err) ->
      cb err
    s.on 'end', ->
      cb null, results
