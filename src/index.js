// Tiny package used to exercise the full neutral-release pipeline
// end to end. Edit this file (or any other in the repo) and commit;
// each push will fire the webhook into Convex.

function hello(name = "world") {
  return `Hello, ${name}!`;
}

console.log('Hello');
console.log('Hey');
module.exports = { hello };
