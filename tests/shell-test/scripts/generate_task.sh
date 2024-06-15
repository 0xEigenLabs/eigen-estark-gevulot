sed -e 's/PHSH/'"$1"'/g' -e 's/VHSH/'"$2"'/g' run_task.tmpl >run_task.sh
chmod +x run_task.sh
