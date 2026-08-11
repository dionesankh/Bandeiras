const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function loadBrowserModule(file, root) {
  const context = {
    window: root,
    console,
    setTimeout,
    clearTimeout
  };
  context.globalThis = root;

  const source = fs.readFileSync(path.join(__dirname, "..", "js", file), "utf8");
  vm.runInNewContext(source, context, { filename: file });

  return root;
}

async function testRankedSessionUsesBackendSequence() {
  const root = {
    FlagGameSupabase: {
      client: {
        rpc(name, params) {
          assert.equal(name, "create_ranked_session");
          assert.deepEqual(JSON.parse(JSON.stringify(params)), {
            p_mode: "world",
            p_variation: "10"
          });

          return Promise.resolve({
            data: {
              session_id: "00000000-0000-4000-8000-000000000001",
              ranked_session_id: "00000000-0000-4000-8000-000000000001",
              nonce: "n".repeat(64),
              expires_at: new Date(Date.now() + 300000).toISOString(),
              config: {
                mode: "world",
                variation: "10",
                seed: "abcdef123456",
                question_codes: ["BR", "AR", "CL"],
                question_count: 3,
                sequence_hash: "hash-123"
              }
            },
            error: null
          });
        }
      }
    }
  };

  loadBrowserModule("ranked-games.js", root);
  const session = await root.FlagGameRanked.createSession("world", "10");

  assert.equal(session.rankedSessionId, "00000000-0000-4000-8000-000000000001");
  assert.equal(session.hasProtectedSequence, true);
  assert.deepEqual(Array.from(session.localConfig.questionCodes), ["BR", "AR", "CL"]);
  assert.equal(session.localConfig.sequenceHash, "hash-123");
}

async function testCreateChallengeFromRankedMatchUsesPromotionRpc() {
  const calls = [];
  const root = {
    FlagGameAuth: {
      isReady: () => Promise.resolve(),
      getCurrentUser: () => Promise.resolve({ id: "user-1" })
    },
    FlagGameSupabase: {
      client: {
        rpc(name, params) {
          calls.push({ name, params });
          return Promise.resolve({
            data: {
              challenge_id: "00000000-0000-4000-8000-000000000002",
              code: "FG-ABC12345"
            },
            error: null
          });
        }
      }
    }
  };

  loadBrowserModule("player-challenges.js", root);
  const result = await root.FlagGamePlayerChallenges.createFromRankedMatch({
    mode: "world",
    quantity: 10,
    rankedSessionId: "00000000-0000-4000-8000-000000000001",
    sequenceHash: "hash-123",
    questionCodes: ["BR", "AR"],
    idempotencyKey: "event-123456"
  });

  assert.equal(result.code, "FG-ABC12345");
  assert.equal(calls.length, 1);
  assert.equal(calls[0].name, "create_challenge_from_ranked_session");
  assert.deepEqual(JSON.parse(JSON.stringify(calls[0].params)), {
    p_ranked_session_id: "00000000-0000-4000-8000-000000000001",
    p_idemp_key: "event-123456"
  });
  assert.equal(Object.hasOwn(calls[0].params, "p_correct"), false);
}

function testRankedIncompleteErrorMapsToRankedResultMissing() {
  const root = {
    navigator: { onLine: true }
  };

  loadBrowserModule("player-challenges.js", root);
  assert.equal(
    root.FlagGamePlayerChallenges.errorCode(new Error("Ranked result is not completed")),
    "ranked_result_missing"
  );
}

function testRankedMetricsIncompleteMapsToSpecificError() {
  const root = {
    navigator: { onLine: true }
  };

  loadBrowserModule("player-challenges.js", root);
  assert.equal(
    root.FlagGamePlayerChallenges.errorCode(new Error("Ranked result metrics are incomplete")),
    "ranked_result_metrics_incomplete"
  );
}

[
  testRankedSessionUsesBackendSequence,
  testCreateChallengeFromRankedMatchUsesPromotionRpc,
  testRankedIncompleteErrorMapsToRankedResultMissing,
  testRankedMetricsIncompleteMapsToSpecificError
].reduce((chain, test) => chain.then(async () => {
  await test();
  console.log(`ok - ${test.name}`);
}), Promise.resolve()).catch(error => {
  console.error(error);
  process.exitCode = 1;
});
