function log(...a){ console.log(new Date().toISOString(), ...a); }
function warn(...a){ console.warn(new Date().toISOString(), ...a); }
function error(...a){ console.error(new Date().toISOString(), ...a); }
module.exports = { log, warn, error };
