// Tiny package used to exercise the full neutral-release pipeline
// end to end. Edit this file (or any other in the repo) and commit;
// each push will fire the webhook into Convex.

function hello(name = "world") {
  return `Hello, ${name}!`;
}

console('1st Commit');

module.exports = { hello };

//Dont include the comment