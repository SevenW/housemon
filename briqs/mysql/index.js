module.exports = {
  info: {
    name: 'mysql',
    description: 'Permanent data storage to mysql',
    rpcs: ['rawRange_mySQL'],
    packages: {
      'mysql': '*'
    }
  },
  factory: 'mysql'
};