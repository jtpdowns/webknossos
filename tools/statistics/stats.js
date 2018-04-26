const { Client } = require("pg");
const fetch = require("node-fetch");

const HOST = "http://localhost:9000";

const MIN_MOVE_ACTIONS = 50;
const MIN_RATIO = 2;
const LAST_X_DAYS = 7;

const ANNOTATIONS_SQL = `
SELECT annotations._id, tracing_id, _user, _task, firstname, lastname, modified
FROM webknossos.annotations
JOIN webknossos.users ON webknossos.annotations._user=webknossos.users._id
WHERE DATE_PART('day', now() - modified) <= ${LAST_X_DAYS}
AND _task IS NOT NULL;`;

function sleep(ms) {
  return new Promise(resolve => {
    setTimeout(resolve, ms);
  });
}

async function connect() {
  const client = new Client();
  await client.connect();

  let res;
  try {
    res = await client.query(ANNOTATIONS_SQL);
  } catch (err) {
    console.log(err);
    process.exit();
  }
  const TOKEN = "INSERT_TOKEN";

  console.log(
    `Configuration:
    Minimum number of move actions: ${MIN_MOVE_ACTIONS}
    Minimum ratio between moveActions/createNodeActions: ${MIN_RATIO}
    Annotations that were modified in the last ${LAST_X_DAYS} days.
    `,
  );

  console.log(`Checking ${res.rows.length} annotations.`);

  for (const entry of res.rows) {
    const url = `${HOST}/data/tracings/skeleton/${
      entry.tracing_id
    }/updateActionStatistics?token=${TOKEN}`;

    await sleep(200);

    try {
      const response = await fetch(url);
      // eslint-disable-next-line no-await-in-loop
      const parsedJSON = await response.json();

      const { updateTracingActionCount: moved, createNodeActionCount: created } = parsedJSON;
      const movedToCreatedRatio = Math.round(moved / created * 10) / 10;

      if (moved > 0 && moved >= MIN_MOVE_ACTIONS && movedToCreatedRatio >= MIN_RATIO) {
        console.log(
          `Moved: ${moved}, Created: ${created}, Moved/Created: ${movedToCreatedRatio} - User: ${
            entry.firstname
          } ${entry.lastname}, TaskId: ${entry._task}, AnnotationId: ${entry._id}, Modified: ${
            entry.modified
          }`,
        );
      }
    } catch (err) {
      console.log(err);
      continue;
    }
  }

  await client.end();
}

connect();
