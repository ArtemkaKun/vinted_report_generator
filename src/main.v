module main

import json
import encoding.csv
import time
import os
import net.http

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

	mut report_request := http.new_request(http.Method.get, 'https://www.vinted.pl/api/v2/wallet/invoices/${year}/${previous_month}',
		'')
	report_request.add_header(http.CommonHeader.accept, 'application/json, text/plain')
	report_request.cookies['_vinted_fr_session'] = os.args[1]

	response := report_request.do() or { panic('Failed to send request') }

	if response.status_code != 200 {
		panic('Failed to get report')
	}

	deserialized_response := json.decode(ReportRequestResponse, response.body) or {
		panic('Failed to deserialize response')
	}

	debit_invoices := deserialized_response.invoice_lines.filter(it.@type == 'debit')

	mut report_writer := csv.new_writer()

	report_writer.write(['Data', 'Przedmiot', 'Kwota']) or { panic('Failed to write header') }

	mut income_sum := 0.0

	for invoice in debit_invoices {
		date := time.parse_iso8601(invoice.date) or { panic('Failed to parse date') }

		report_writer.write([date.str().split(' ')[0], invoice.subtitle, invoice.amount]) or {
			panic('Failed to write invoice')
		}

		income_sum += invoice.amount.f64()
	}

	report_writer.write(['', 'Suma', '${income_sum:.2}']) or { panic('Failed to write sum') }

	os.write_file('report.csv', report_writer.str()) or { panic('Failed to write report') }
}
