import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const scriptDir = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));
const projectRoot = path.resolve(scriptDir, "..");
const manuscriptDir = path.join(projectRoot, "6_output", "main_output", "manuscript");
const tablesDir = path.join(manuscriptDir, "tables");
const picturesDir = path.join(manuscriptDir, "pictures");
const inputPath = path.join(tablesDir, "oopg_pens_parade_monthly_workbook_data.json");
const figurePath = path.join(picturesDir, "oopg_pens_parade_noadd_monthly.png");
const outputPath = path.join(tablesDir, "oopg_pens_parade_simple.xlsx");
const previewPath = path.join(tablesDir, "_workbook_previews", "simple_pen_parade.png");

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

function address(rowCount, colCount, startRow = 1) {
  return `A${startRow}:${colName(colCount - 1)}${startRow + rowCount - 1}`;
}

function dataUrlFromPng(bytes) {
  return `data:image/png;base64,${Buffer.from(bytes).toString("base64")}`;
}

const payload = JSON.parse(await fs.readFile(inputPath, "utf8"));
const pngBytes = await fs.readFile(figurePath);
const { summary, data } = payload;

const headers = [
  "Poverty line=1",
  "rank",
  "Pre-OOPG HH Consumption",
  "Post-OOPG HH Consumption",
  "psu_number",
  "hh_number",
  "pcep_mo_real",
  "oopg_pc_mo_real",
  "raw_post_oopg_mo_real",
  "negative_raw_post_oopg",
];

const rows = data.map((row) => [
  1,
  row.cum_population_share / 100,
  row.pre_poverty_multiple,
  row.post_poverty_multiple,
  row.psu_number,
  row.hh_number,
  row.pcep_mo_real,
  row.oopg_pc_mo_real,
  row.raw_post_oopg_mo_real,
  row.negative_raw_post_oopg,
]);

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Pen Parade");
sheet.showGridLines = false;

sheet.getRange("A1:J1").merge();
sheet.getRange("A1").values = [["OOPG Pen's Parade - No-Addback Monthly Per-Capita Scenario"]];
sheet.getRange("A1").format = {
  fill: "#1F4E79",
  font: { bold: true, color: "#FFFFFF", size: 14 },
};

sheet.getRange("A3:J5").values = [
  [
    "Pre poverty",
    "Post poverty",
    "Change",
    "People pushed",
    "Households pushed",
    "Negative raw post",
    "Pre welfare",
    "OOPG",
    "Raw post",
    "Post floor",
  ],
  [
    summary.pre_oopg_poverty_pct / 100,
    summary.post_oopg_poverty_pct / 100,
    summary.poverty_change_pp / 100,
    summary.people_pushed,
    summary.households_pushed,
    summary.negative_raw_post_oopg_households,
    "pcep / 12",
    "(oopg / hhsize) / paasche",
    "pre - OOPG",
    "max(raw post, 0)",
  ],
  [
    "Percent",
    "Percent",
    "Percentage points",
    "People",
    "Households",
    "Households",
    "Monthly real PC NPR",
    "Monthly real PC NPR",
    "Monthly real PC NPR",
    "Monthly real PC NPR",
  ],
];
sheet.getRange("A3:J3").format = {
  fill: "#D9EAF7",
  font: { bold: true },
  wrapText: true,
};
sheet.getRange("A4:C4").format.numberFormat = "0.00%";
sheet.getRange("D4:F4").format.numberFormat = "#,##0";
sheet.getRange("G4:J5").format.wrapText = true;

sheet.images.add({
  dataUrl: dataUrlFromPng(pngBytes),
  anchor: {
    from: { row: 6, col: 0 },
    extent: { widthPx: 940, heightPx: 420 },
  },
});

const tableStart = 31;
const matrix = [headers, ...rows];
sheet.getRange(address(matrix.length, headers.length, tableStart)).values = matrix;
const tableRange = address(matrix.length, headers.length, tableStart);
const table = sheet.tables.add(tableRange, true, "SimplePensParade");
table.style = "TableStyleMedium2";
table.showFilterButton = true;
sheet.freezePanes.freezeRows(tableStart);

const headerRange = sheet.getRange(`A${tableStart}:J${tableStart}`);
headerRange.format = {
  fill: "#1F4E79",
  font: { bold: true, color: "#FFFFFF" },
  wrapText: true,
};

sheet.getRange(`A${tableStart + 1}:D${tableStart + rows.length}`).format.numberFormat = "0.000";
sheet.getRange(`G${tableStart + 1}:I${tableStart + rows.length}`).format.numberFormat = "#,##0.00";
sheet.getRange(`J${tableStart + 1}:J${tableStart + rows.length}`).conditionalFormats.add("cellIs", {
  operator: "equal",
  formula: "TRUE",
  format: { fill: "#F8CBAD", font: { bold: true, color: "#9C0006" } },
});
sheet.getRange(`I${tableStart + 1}:I${tableStart + rows.length}`).conditionalFormats.add("cellIs", {
  operator: "lessThan",
  formula: "0",
  format: { fill: "#FCE4D6", font: { bold: true, color: "#9C0006" } },
});

const widths = [105, 85, 150, 155, 95, 95, 130, 130, 145, 145];
widths.forEach((px, i) => {
  sheet.getRange(`${colName(i)}:${colName(i)}`).format.columnWidthPx = px;
});

await fs.mkdir(path.dirname(previewPath), { recursive: true });
const preview = await workbook.render({
  sheetName: "Pen Parade",
  range: "A1:J48",
  scale: 1,
  format: "png",
});
await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

const inspect = await workbook.inspect({
  kind: "table",
  range: "Pen Parade!A3:J5",
  include: "values",
  tableMaxRows: 3,
  tableMaxCols: 10,
});
console.log(inspect.ndjson);

const scan = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "formula error scan",
});
console.log(scan.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
console.log(`Saved: ${outputPath}`);
