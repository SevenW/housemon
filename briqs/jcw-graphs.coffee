exports.info =
  name: 'graphs'
  description: 'Show a graph with historical dataT'
  menus: [
    title: 'Graphs'
    controller: 'GraphsCtrl'
  ]
  connections:
    feeds:
      'hist': 'redis'
