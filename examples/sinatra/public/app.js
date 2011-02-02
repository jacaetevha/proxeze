function show_file(name) {
  $.get("/" + name, function(data) {
    $('#file_contents').html("<code><pre>" + data + "</pre></code>");
  });
}