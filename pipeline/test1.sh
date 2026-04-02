tail -n +2 config/sample_sheet.tsv | while IFS=$'\t' read -r sample_id gsm srr condition patient_id fraction; do
    echo "sample_id='${sample_id}'"
    break
done