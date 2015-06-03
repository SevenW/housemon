module.exports =

  announcer: 30

  descriptions:
    ['PD', 'PE', 'PG']

  PD:
    evt1:
      title: 'E verbruik - dal'
      unit: 'kWh'
      scale: 3
      min: 0
    evt2:
      title: 'E verbruik - piek'
      unit: 'kWh'
      scale: 3
      min: 0
    elt1:
      title: 'E levering - dal'
      unit: 'kWh'
      scale: 3
      min: 0
    elt2:
      title: 'E levering - piek'
      unit: 'kWh'
      scale: 3
      min: 0
    evdt1:
      title: 'E dag verbruik - dal'
      unit: 'kWh'
      scale: 3
      min: 0
    evdt2:
      title: 'E dag verbruik - piek'
      unit: 'kWh'
      scale: 3
      min: 0
    eldt1:
      title: 'E dag levering - dal'
      unit: 'kWh'
      scale: 3
      min: 0
    eldt2:
      title: 'E dag levering - piek'
      unit: 'kWh'
      scale: 3
      min: 0
    evd:
      title: 'E dag verbruik - totaal'
      unit: 'kWh'
      scale: 3
      min: 0
    eld:
      title: 'E dag levering - totaal'
      unit: 'kWh'
      scale: 3
      min: 0
    cnt:
      title: 'P1 logs/dag'

  PE:
    etrf:
      title: 'E tarief'
    epv:
      title: 'P verbruik'
      unit: 'W'
      scale: -1
      min: 0
      max: 15000
    epl:
      title: 'P levering'
      unit: 'W'
      scale: -1
      min: 0
      max: 10000

  PG:
    gas:
      title: 'G verbruik'
      unit: 'm3'
      scale: 3
      min: 0

  feed: 'rf12.packet'

  decode: (raw, cb) ->
    #console.log "p1scannerCL entry"
    type = raw.toString undefined, 1, 3
    #console.log type
    if type == 'PD'
      result =
        tag: 'PD'
        evt1: raw.readUInt32BE(3)
        evt2: raw.readUInt32BE(7)
        elt1: raw.readUInt32BE(11)
        elt2: raw.readUInt32BE(15)
        evdt1: raw.readUInt32BE(19)
        evdt2: raw.readUInt32BE(23)
        eldt1: raw.readUInt32BE(27)
        eldt2: raw.readUInt32BE(31)
        evd: raw.readUInt32BE(19) + raw.readUInt32BE(23)
        evl: raw.readUInt32BE(27) + raw.readUInt32BE(31)
        cnt: raw.readUInt16BE(35)
    else if type == 'PE'
      result =
        tag: 'PE'
        epv: raw.readUInt32BE(3)
        epl: raw.readUInt32BE(7)
        etrf: raw.readUInt8(11)
    else if type == 'PG'
      result =
        tag: 'PG'
        gas: raw.readUInt32BE(3)

    #console.log result
    cb result
