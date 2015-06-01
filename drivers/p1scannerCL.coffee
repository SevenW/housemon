module.exports =

  announcer: 30

  descriptions:
    ['PD', 'PE', 'PG']

  PD:
    use1:
      title: 'Elec usage - low'
      unit: 'kWh'
      scale: 3
      min: 0
    use2:
      title: 'Elec usage - high'
      unit: 'kWh'
      scale: 3
      min: 0
    gen1:
      title: 'Elec return - low'
      unit: 'kWh'
      scale: 3
      min: 0
    gen2:
      title: 'Elec return - high'
      unit: 'kWh'
      scale: 3
      min: 0
    cuse1:
      title: 'Cum Elec usage - low'
      unit: 'kWh'
      scale: 3
      min: 0
    cuse2:
      title: 'Cum Elec usage - high'
      unit: 'kWh'
      scale: 3
      min: 0
    cgen1:
      title: 'Cum Elec return - low'
      unit: 'kWh'
      scale: 3
      min: 0
    cgen2:
      title: 'Cum Elec return - high'
      unit: 'kWh'
      scale: 3
      min: 0

  PE:
    mode:
      title: 'Elec tariff'
    usew:
      title: 'Elec usage now'
      unit: 'W'
      scale: -1
      min: 0
      max: 15000
    genw:
      title: 'Elec return now'
      unit: 'W'
      scale: -1
      min: 0
      max: 10000

  PG:
    gas:
      title: 'Gas total'
      unit: 'm3'
      scale: 3
      min: 0

  feed: 'rf12.packet'

  decode: (raw, cb) ->
    console.log "p1scannerCL entry"
    type = raw.toString undefined, 1, 3
    console.log type
    if type == 'PD'
      result =
        tag: 'PD'
        cuse1: raw.readUInt32BE(3)
        cuse2: raw.readUInt32BE(7)
        cgen1: raw.readUInt32BE(11)
        cgen2: raw.readUInt32BE(15)
        use1: raw.readUInt32BE(19)
        use2: raw.readUInt32BE(23)
        gen1: raw.readUInt32BE(27)
        gen2: raw.readUInt32BE(31)
    else if type == 'PE'
      result =
        tag: 'PE'
        usew: raw.readUInt32BE(3)
        genw: raw.readUInt32BE(7)
        mode: raw.readUInt8(11)
    else if type == 'PG'
      result =
        tag: 'PG'
        gas: raw.readUInt32BE(3)

    #console.log result
    cb result
