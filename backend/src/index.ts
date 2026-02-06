import { ApolloServer } from "@apollo/server";
import { startStandaloneServer } from "@apollo/server/standalone";
import { typeDefs } from "./schema.js";
import { resolvers } from "./resolvers.js";

async function main() {
  const server = new ApolloServer({ typeDefs, resolvers });
  const port = Number(process.env.PORT) || 4000;

  const { url } = await startStandaloneServer(server, {
    listen: { port, host: "0.0.0.0" },
  });

  console.log(`🚀 GraphQL server ready at ${url}`);
}

main().catch((err) => {
  console.error("Server failed to start:", err);
  process.exit(1);
});
