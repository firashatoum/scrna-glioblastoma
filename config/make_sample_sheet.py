import csv
import re
import sys

# Mapping from GSM accession to sample label from GEO
gsm_to_label = {
    "GSM5518596": "rGBM-01-A",  "GSM5518597": "rGBM-01-B",
    "GSM5518598": "rGBM-01-C",  "GSM5518599": "rGBM-01-D",
    "GSM5518600": "ndGBM-01-A", "GSM5518601": "ndGBM-01-C",
    "GSM5518602": "ndGBM-01-D", "GSM5518603": "ndGBM-01-F",
    "GSM5518604": "ndGBM-11-A", "GSM5518605": "ndGBM-11-B",
    "GSM5518606": "ndGBM-11-C", "GSM5518607": "ndGBM-11-D",
    "GSM5518608": "ndGBM-02-1", "GSM5518609": "ndGBM-02-2",
    "GSM5518610": "ndGBM-02-4", "GSM5518611": "ndGBM-02-5",
    "GSM5518612": "rGBM-02-2",  "GSM5518613": "rGBM-02-3",
    "GSM5518614": "rGBM-02-4",  "GSM5518615": "rGBM-02-5",
    "GSM5518616": "rGBM-03-1",  "GSM5518617": "rGBM-03-2",
    "GSM5518618": "rGBM-03-3",  "GSM5518619": "rGBM-04-1",
    "GSM5518620": "rGBM-04-2",  "GSM5518621": "rGBM-04-3",
    "GSM5518622": "rGBM-04-4",  "GSM5518623": "ndGBM-03-1",
    "GSM5518624": "ndGBM-03-2", "GSM5518625": "ndGBM-03-3",
    "GSM5518626": "rGBM-05-1",  "GSM5518627": "rGBM-05-2",
    "GSM5518628": "rGBM-05-3",  "GSM5518629": "ndGBM-10",
    "GSM5518630": "LGG-04-1",   "GSM5518631": "LGG-04-2",
    "GSM5518632": "LGG-04-3",   "GSM5518633": "ndGBM-04",
    "GSM5518634": "ndGBM-05",   "GSM5518635": "ndGBM-06",
    "GSM5518636": "ndGBM-07",   "GSM5518637": "ndGBM-08",
    "GSM5518638": "LGG-03",     "GSM5518639": "ndGBM-09",
}

def parse_label(label):
    match = re.match(r'([a-zA-Z]+)-(\d+)-?([A-Za-z0-9]*)', label)
    if match:
        condition  = match.group(1)
        patient_id = match.group(2)
        fraction   = match.group(3)
    else:
        condition, patient_id, fraction = label, "", ""
    return condition, patient_id, fraction

def main(sra_table_path, output_path):
    rows_out = []

    with open(sra_table_path, newline='') as infile:
        reader = csv.DictReader(infile)
        for row in reader:
            gsm   = row["Sample Name"].strip()
            srr   = row["Run"].strip()
            label = gsm_to_label.get(gsm, "UNKNOWN")
            condition, patient_id, fraction = parse_label(label)
            rows_out.append({
                "sample_id"    : label,
                "gsm_accession": gsm,
                "srr_accession": srr,
                "condition"    : condition,
                "patient_id"   : patient_id,
                "fraction"     : fraction,
            })

    rows_out.sort(key=lambda x: x["sample_id"])

    header = ["sample_id", "gsm_accession", "srr_accession",
              "condition", "patient_id", "fraction"]

    with open(output_path, 'w', newline='') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=header, delimiter='\t')
        writer.writeheader()
        for r in rows_out:
            writer.writerow(r)

    print(f"Sample sheet written to {output_path} ({len(rows_out)} samples)")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python make_sample_sheet.py SraRunTable.csv sample_sheet.tsv")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])