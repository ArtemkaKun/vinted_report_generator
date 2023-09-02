module main

import json
import encoding.csv
import time
import os

struct ReportRequestResponse {
	invoice_lines []InvoiceLine
}

struct InvoiceLine {
	@type    string
	subtitle string
	date     string
	amount   string
}

fn main() {
	today := time.now()
	mut previous_month := today.custom_format('M').int() - 1
	mut year := today.custom_format('YYYY').int()

	if previous_month == 0 {
		previous_month = 12
		year -= 1
	}

	result := os.execute("curl 'https://www.vinted.pl/api/v2/wallet/invoices/${year}/${previous_month}' -H 'Accept: application/json, text/plain' -H 'Cookie: _vinted_fr_session=${os.args[1]};'")

	needed_data := '{${result.output.all_after_first('{')}'

	deserialized_response := json.decode(ReportRequestResponse, needed_data) or {
		panic('Failed to deserialize response')
	}

	debit_invoices := deserialized_response.invoice_lines.filter(it.@type == 'debit')

	mut report_writer := csv.new_writer()

	report_writer.write(['Data', 'Przedmiot', 'Kwota']) or { panic('Failed to write header') }

	for invoice in debit_invoices {
		date := time.parse_iso8601(invoice.date) or { panic('Failed to parse date') }

		report_writer.write([date.str().split(' ')[0], invoice.subtitle, invoice.amount]) or {
			panic('Failed to write invoice')
		}
	}

	os.write_file('report.csv', report_writer.str()) or { panic('Failed to write report') }
}
