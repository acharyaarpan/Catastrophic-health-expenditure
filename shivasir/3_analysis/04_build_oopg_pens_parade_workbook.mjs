import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const projectRoot = path.resolve(
  path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")),
  "..",
);
const manuscriptDir = path.join(projectRoot, "6_output", "main_output", "manuscript");
const tablesDir = path.join(manuscriptDir, "tables");
const inputPath = path.join(tablesDir, "oopg_pens_parade_monthly_workbook_data.json");
const outputPath = path.join(tablesDir, "oopg_pens_parade_monthly_audit.xlsx");
const previewDir = path.join(tablesDir, "_workbook_previews");

function colName(index) {
  let n = index + 1;
  let out = "";
  while (n > 0) {
    const rem = (n - 1) % 26;
    out = String.fromCharCode(65 + rem) + out;
    n = Math.floor((n - 1) / 26);
  }
  return out;
}

function rangeAddress(rowCount, colCount) {
  return `A1:${colName(colCount - 1)}${rowCount}`;
}

function asMatrix(headers, rows) {
  return [headers, ...rows.map((row) => headers.map((h) => row[h] ?? null))];
}

function setWidths(sheet, widthsPx) {
  widthsPx.forEach((px, idx) => {
    sheet.getRange(`${colName(idx)}:${colName(idx)}`).format.columnWidthPx = px;
  });
}

function styleDataSheet(sheet, headers, rowCount, tableName) {
  const lastCol = colName(headers.length - 1);
  sheet.freezePanes.freezeRows(1);
  sheet.getRange(`A1:${lastCol}1`).format = {
    fill: "#1F4E79",
    font: { bold: true, color: "#FFFFFF" },
    wrapText: true,
  };
  sheet.getRange(`A1:${lastCol}${rowCount}`).format.font = { size: 9 };
  const table = sheet.tables.add(`A1:${lastCol}${rowCount}`, true, tableName);
  table.style = "TableStyleMedium2";
  table.showFilterButton = true;

  const numericCols = [
    "hhsize",
    "hhs_wt",
    "ind_wt",
    "pcep_mo_real",
    "pline_mo_real",
    "oopg",
    "oopg_pc_mo_real",
    "raw_post_oopg_mo_real",
    "post_oopg_mo_real_floored",
    "pre_poverty_multiple",
    "post_poverty_multiple",
    "cum_population_share",
    "paasche",
    "pcep",
    "pline",
  ];
  for (const header of numericCols) {
    const idx = headers.indexOf(header);
    if (idx >= 0) {
      sheet.getRange(`${colName(idx)}2:${colName(idx)}${rowCount}`).format.numberFormat =
        "#,##0.00";
    }
  }

  const rawIdx = headers.indexOf("raw_post_oopg_mo_real");
  if (rawIdx >= 0) {
    sheet
      .getRange(`${colName(rawIdx)}2:${colName(rawIdx)}${rowCount}`)
      .conditionalFormats.add("cellIs", {
        operator: "lessThan",
        formula: "0",
        format: {
          fill: "#FCE4D6",
          font: { color: "#9C0006", bold: true },
        },
      });
  }

  const flagIdx = headers.indexOf("negative_raw_post_oopg");
  if (flagIdx >= 0) {
    sheet
      .getRange(`${colName(flagIdx)}2:${colName(flagIdx)}${rowCount}`)
      .conditionalFormats.add("cellIs", {
        operator: "equal",
        formula: "TRUE",
        format: {
          fill: "#F8CBAD",
          font: { color: "#9C0006", bold: true },
        },
      });
  }

  setWidths(sheet, [
    100, 100, 70, 80, 70, 80, 105, 110, 135, 130, 95, 130, 165, 170, 140, 135,
    145, 120, 120, 170, 120, 145, 90, 125, 125,
  ]);
}

const payload = JSON.parse(await fs.readFile(inputPath, "utf8"));
const { summary, data, negative_rows: negativeRows, fields, notes } = payload;

const workbook = Workbook.create();
const summarySheet = workbook.worksheets.add("Summary");
const dataSheet = workbook.worksheets.add("Data");
const negativeSheet = workbook.worksheets.add("Negative raw post");
const readmeSheet = workbook.worksheets.add("README");

summarySheet.showGridLines = false;
summarySheet.getRange("A1:D1").merge();
summarySheet.getRange("A1").values = [["OOPG Pen's Parade Monthly Per-Capita Audit"]];
summarySheet.getRange("A1").format = {
  fill: "#1F4E79",
  font: { bold: true, color: "#FFFFFF", size: 14 },
};
summarySheet.getRange("A3:B14").values = [
  ["Metric", "Value"],
  ["Households", summary.households],
  ["Pre-OOPG poverty (%)", summary.pre_oopg_poverty_pct],
  ["Post-OOPG poverty (%)", summary.post_oopg_poverty_pct],
  ["Change (percentage points)", summary.poverty_change_pp],
  ["People pushed below poverty", summary.people_pushed],
  ["Households pushed below poverty", summary.households_pushed],
  ["Raw post-OOPG negative households", summary.negative_raw_post_oopg_households],
  ["Mean pre-OOPG monthly PC welfare", summary.mean_pre_oopg_mo_real],
  ["Mean monthly PC OOPG", summary.mean_oopg_pc_mo_real],
  ["Mean post-OOPG monthly PC welfare", summary.mean_post_oopg_mo_real_floored],
  ["Mean monthly poverty line", summary.mean_pline_mo_real],
];
summarySheet.getRange("A3:B3").format = {
  fill: "#D9EAF7",
  font: { bold: true },
};
summarySheet.getRange("B5:B6").format.numberFormat = "0.00";
summarySheet.getRange("B7:B10").format.numberFormat = "#,##0";
summarySheet.getRange("B11:B14").format.numberFormat = "#,##0.00";
summarySheet.getRange("A16:D16").merge();
summarySheet.getRange("A16").values = [["Definitions used in this workbook"]];
summarySheet.getRange("A16").format = {
  fill: "#D9EAD3",
  font: { bold: true },
};
summarySheet.getRange("A17:B23").values = [
  ["pcep_mo_real", "pcep / 12"],
  ["pline_mo_real", "pline / 12"],
  ["oopg_pc_mo_real", "(monthly household oopg / hhsize) / paasche"],
  ["raw_post_oopg_mo_real", "pcep_mo_real - oopg_pc_mo_real"],
  ["post_oopg_mo_real_floored", "max(raw_post_oopg_mo_real, 0)"],
  ["negative_raw_post_oopg", "TRUE when raw_post_oopg_mo_real < 0"],
  ["pushed_below_poverty_oopg", "TRUE when pre >= poverty line and post < poverty line"],
];
setWidths(summarySheet, [320, 210, 160, 160]);

const dataMatrix = asMatrix(fields, data);
dataSheet.getRange(rangeAddress(dataMatrix.length, fields.length)).values = dataMatrix;
styleDataSheet(dataSheet, fields, dataMatrix.length, "OOPGPensParadeData");

const negativeMatrix = asMatrix(fields, negativeRows);
negativeSheet.getRange(rangeAddress(Math.max(negativeMatrix.length, 2), fields.length)).values =
  negativeMatrix.length > 1 ? negativeMatrix : [fields, fields.map(() => null)];
styleDataSheet(
  negativeSheet,
  fields,
  Math.max(negativeMatrix.length, 2),
  "OOPGNegativeRawPost",
);

readmeSheet.showGridLines = false;
readmeSheet.getRange("A1:D1").merge();
readmeSheet.getRange("A1").values = [["README"]];
readmeSheet.getRange("A1").format = {
  fill: "#1F4E79",
  font: { bold: true, color: "#FFFFFF", size: 14 },
};
const notesEndRow = 2 + notes.length;
readmeSheet.getRange(`A3:A${notesEndRow}`).values = notes.map((note) => [note]);
readmeSheet.getRange(`A3:A${notesEndRow}`).format.wrapText = true;
setWidths(readmeSheet, [720, 120, 120, 120]);

await fs.mkdir(previewDir, { recursive: true });
for (const [sheetName, range] of [
  ["Summary", "A1:D23"],
  ["Data", "A1:Y20"],
  ["Negative raw post", "A1:Y20"],
  ["README", `A1:D${notesEndRow}`],
]) {
  const preview = await workbook.render({
    sheetName,
    range,
    scale: 1,
    format: "png",
  });
  const bytes = new Uint8Array(await preview.arrayBuffer());
  await fs.writeFile(
    path.join(previewDir, `${sheetName.replaceAll(" ", "_").toLowerCase()}.png`),
    bytes,
  );
}

const tableInspect = await workbook.inspect({
  kind: "table",
  range: "Summary!A3:B14",
  include: "values",
  tableMaxRows: 12,
  tableMaxCols: 2,
});
console.log(tableInspect.ndjson);

const errorScan = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "formula error scan",
});
console.log(errorScan.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
console.log(`Saved: ${outputPath}`);
process.exit(0);
