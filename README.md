# HouseMon 0.70CL

Real-time home monitoring and automation.

More info at <http://jeelabs.org/tag/housemon/>.

[![Dependency Status](https://gemnasium.com/jcw/housemon.png)](https://gemnasium.com/jcw/housemon)

# Installation

*(Note: go to [this page][B] for detailed Raspberry Pi setup instructions)*

Install [Node.js][N] (it has to be version 0.10.x) and [redis][R], then:

    $ git clone https://github.com/jcw/housemon.git
    $ cd housemon
    $ npm install
    
Make sure Redis is running (this app uses database #1, see `local.json`):

    $ redis-server &

Then launch the app as a Node.js web server:

    $ npm start

Now browse to <http://localhost:3333/> (this can be changed in `local.json`).

  [B]: http://jeelabs.org/2013/02/15/dijn-08-set-up-node-js-and-redis/
  [N]: http://nodejs.org/
  [R]: http://redis.io/

# Documentation

If you want to start exploring the (early) features of HouseMon, keep these  
points in mind and check <http://jeelabs.org/tag/housemon/> for the latest news:

* the "logger" triggers on "incoming" events, as emitted by the "rf12demo" briq
* the "Readings" page needs drivers and mappings from node ID to that driver
* the "Status" page also needs mappings from node ID's to named locations
* the "archiver" and "history" briqs use status changes, so get that going first
* the "Graphs" page only works off history data so far, i.e. up to 48 hours back

There is some documentation in the `docs/` folder, but things *do* change fast!

# License

MIT
