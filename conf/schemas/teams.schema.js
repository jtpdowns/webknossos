db.runCommand({
  collMod: "teams",
  validator: {
    $and: [
      {
        name: { $regex: "^[A-Za-z0-9-_]+$", $exists: true },
      },
      {
        $or: [{ parent: { $type: "string" } }, { parent: { $exists: false } }],
      },
      {
        roles: {
          $type: "array",
          $exists: true,
          $elemMatch: { $elemMatch: { name: { $type: "string", $exists: true } } },
        },
      },
      {
        $or: [{ owner: { $type: "objectId" } }, { owner: { $exists: false } }],
      },
      {
        $or: [
          { behavesLikeRootTeam: { $type: "bool" } },
          { behavesLikeRootTeam: { $exists: false } },
        ],
      },
      {
        _id: { $type: "objectId", $exists: true },
      },
    ],
  },
});
