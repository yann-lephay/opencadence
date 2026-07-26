#!/bin/zsh

cd "$(dirname "$0")" || exit 1

if [ ! -d "node_modules" ]; then
  echo "Première ouverture : installation d’OpenCadence…"
  npm install || exit 1
fi

(sleep 2 && open "http://localhost:3015") &
npm run dev
