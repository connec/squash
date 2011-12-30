if(typeof window === 'undefined') {
  exports.env = 'commonjs';
} else {
  window.env = 'browser';
}