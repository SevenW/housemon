var archiveValue, db, mysql, state, storeValue;

state = require('../../server/state');

mysql = require('mysql');

db = state.mdb;

archiveValue = function(time, param, value) {
	if (param == 'P1 meter - P verbruik') {
		var ts_date = new Date(0);
		ts_date.setUTCSeconds(time/1000);
		var post  = {ts: ts_date, id: 1, sid: param, value: 10*value};
		//console.log(post);
		var query = db.query('INSERT INTO timeseries SET ?', post, function(err, result) {
			//console.log(result);
			if (err) {
			  console.log(err);
			}
		});
	}
};

storeValue = function(obj, oldObj) {
  if (obj != null) {
	console.log(obj);
    return archiveValue(obj.time, obj.key, obj.origval);
  }
};

module.exports = (function() {
  function _Class() {
    state.on('set.status', storeValue);
    state.on('reprocess.status', archiveValue);
  }

  _Class.prototype.destroy = function() {
    state.off('set.status', storeValue);
    return state.off('reprocess.status', archiveValue);
  };

  _Class.rawRange_mySQL = function(key, from, to, cb) {
    // var now, prefix, results, s;
    // now = Date.now();
    // if (from < 0) {
      // from += now;
    // }
    // if (to <= 0) {
      // to += now;
    // }
    // prefix = "reading~" + key + "~";
    // results = [];
    // s = db.createReadStream({
      // start: prefix + from,
      // end: prefix + to
    // });
    // s.on('data', function(data) {
      // results.push(+data.value);
      // return results.push(+data.key.substr(prefix.length));
    // });
    // s.on('error', function(err) {
      // return cb(err);
    // });
    // return s.on('end', function() {
      // return cb(null, results);
    // });
  };

  return _Class;

})()