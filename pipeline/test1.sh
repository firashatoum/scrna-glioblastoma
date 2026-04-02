tail -n +2 config/sample_sheet.tsv | while IFS=$'\t' read -r sample_id gsm srr condition patient_id fraction; do
    if [[ "${sample_id}" == "rGBM-01-A" ]]; then
        echo "MATCH FOUND"
        echo "srr=${srr}"
    fi
done