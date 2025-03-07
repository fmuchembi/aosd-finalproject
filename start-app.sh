#!/bin/bash

# Look for ee_Initialize in global.R first
if [ -f /srv/shiny-server/global.R ] && grep -q "ee_Initialize()" /srv/shiny-server/global.R; then
  # Create a backup
  cp /srv/shiny-server/global.R /srv/shiny-server/global.R.original
  
  # Replace the ee_Initialize call
  sed -i "s/ee_Initialize()/ee_Initialize(py_env = \"\/opt\/rgee\")/g" /srv/shiny-server/global.R
  
  echo "Modified global.R to use the correct Python environment"
fi

# Then look in server.R
if [ -f /srv/shiny-server/server.R ] && grep -q "ee_Initialize()" /srv/shiny-server/server.R; then
  # Create a backup
  cp /srv/shiny-server/server.R /srv/shiny-server/server.R.original
  
  # Replace the ee_Initialize call
  sed -i "s/ee_Initialize()/ee_Initialize(py_env = \"\/opt\/rgee\")/g" /srv/shiny-server/server.R
  
  echo "Modified server.R to use the correct Python environment"
fi

# Start Shiny server
exec /usr/bin/shiny-server