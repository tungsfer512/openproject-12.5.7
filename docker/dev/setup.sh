docker compose build
docker compose run --rm backend setup
docker compose run --rm frontend npm install
docker compose up -d