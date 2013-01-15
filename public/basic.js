(function() {
  var hello;

  hello = function(world) {
    return "!";
  };

  console.log('HELLO' + ' world' + hello());

}).call(this);
