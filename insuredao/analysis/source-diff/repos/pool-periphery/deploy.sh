echo 'running build.sh'

npx hardhat clean

if [ -z "$NETWORK" ]; then
  echo "ERROR: NETWORK environment variable required"
  exit 1
fi

npx mustache scripts/config/$NETWORK.json scripts/deploy.template.ts > scripts/deploy.ts

echo 'generated deploy.ts'

npx hardhat run scripts/deploy.ts --network $NETWORK