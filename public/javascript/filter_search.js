function searchContacts() {
  // Declare variables
  var input, filter, ul, h3, li, a, i, txtValue;
  input = document.getElementById('search');
  filter = input.value.toUpperCase();
  ul = document.getElementById("contacts");
  h3 = ul.getElementsByClassName("letter");
  li = ul.getElementsByTagName('li');

  // Loop through all list items, and hide those who don't match the search query
  for (i = 0; i < li.length; i++) {
    a = li[i].getElementsByTagName("a")[0];
    txtValue = a.textContent || a.innerText;
    if (txtValue.toUpperCase().indexOf(filter) > -1) {
      li[i].style.display = "";
      h3[i].style.display = "";
    } else {
      li[i].style.display = "none";
      h3[i].style.display = "none";
    }
  }
}