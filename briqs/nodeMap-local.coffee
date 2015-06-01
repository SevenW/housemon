# Static node map and other data. This information is temporary, until a real
# admin/config interface is implemented on the client side. The information in
# here reflects the settings used at JeeLabs, but is also used by the "replay"
# briq, which currently works off one of the JeeLabs log files.
#
# This file is not treated as briq because it does not export an 'info' entry.
#
# To add your own settings: do *NOT* edit this file, but create a new one next
# to it called "nodeMap-local.coffee". For example, if you use group 212:
#
#   exports.rf12nodes = 
#     212:
#       1: 'roomNode'
#       2: ...etc
#
# The settings in the local file will be merged (and can override) the settings
# in this file. If you override settings, the "replay" briq may no longer work.

# this is still used for parsing logs which do not include announcer packets
# TODO: needs to be time-dependent, since the config can change over time
exports.rf12nodes =
  178:
    3: 'roomNodeSQ'
    4: 'bmp085SQ'
    22: 'weatherStation'
    23: 'weatherStation'
    30: 'p1scannerCL'
    31: 'clTime'

# devices are mapped to RF12 configs, since that is not present in log files
# TODO: same time-dependent comment as above, this mapping is not fixed
# this section is only used by the 'rf12-replay' briq
exports.rf12devices =
  '/dev/CL1':
    recvid: 1
    group: 178
    band: 868

# the default is used by the "reprocess" briq when no other info is available
exports.rf12default =
    recvid: 1
    group: 178
    band: 868

# static data, used for local testing and for replay of the JeeLabs data
# these map incoming sensor identifiers to locations in the house (in Dutch)
exports.locations =
  'RF12:178:1': title: 'raspberry pi'
  'RF12:178:3': title: 'woonkamer'
  'RF12:178:4': title: 'barometer'
  'RF12:178:22': title: 'zolder'
  'RF12:178:23': title: 'zolderOOK'
  'RF12:178:30': title: 'P1 meter'
  'RF12:178:31': title: 'centrallogger time'
