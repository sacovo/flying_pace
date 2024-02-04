const btn = document.querySelector("#btn-json");

btn.addEventListener("click", (e) => {
  e.preventDefault();

  fetch("/json/", {
    method: "POST",
    body: JSON.stringify({ test: "Hallo", a: [1, 2, 3, 4] }),
  })
    .then((response) => response.json())
    .then((d) => console.log(d));
});
