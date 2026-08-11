const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function loadChallengeModule() {
  const context = {
    window: {},
    console
  };
  context.globalThis = context.window;

  const source = fs.readFileSync(
    path.join(__dirname, "..", "js", "challenges.js"),
    "utf8"
  );

  vm.runInNewContext(source, context);

  return context.window.FlagGameChallenge;
}

function testBuildQuestionsUsesBackendOrder() {
  const Challenge = loadChallengeModule();
  const countries = [
    { code: "BR", continent: "south-america" },
    { code: "AR", continent: "south-america" },
    { code: "CL", continent: "south-america" }
  ];

  const questions = Challenge.buildQuestions(countries, {
    mode: "continent",
    continent: "south-america",
    questionCodes: ["CL", "BR", "AR"]
  });

  assert.deepEqual(questions.map(country => country.code), ["CL", "BR", "AR"]);
}

[
  testBuildQuestionsUsesBackendOrder
].forEach(test => {
  test();
  console.log(`ok - ${test.name}`);
});
