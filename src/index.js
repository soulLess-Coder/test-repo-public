// Tiny package used to exercise the full neutral-release pipeline
// end to end. Edit this file (or any other in the repo) and commit;
// each push will fire the webhook into Convex.

function hello(name = "world") {
  return `Hello, ${name}!`;
}

console.log('First Commit- Public');
console.log('Second Commit- Private');

module.exports = { hello };

//Dont include the comment