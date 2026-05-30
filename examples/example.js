// Page Domino's locations within an Amsterdam bounding box
import { Client } from "@topolab/sdk";

const tl = new Client({ apiKey: "tlb_prod_..." });
const fc = await tl.dataset("nl-domino-poi").items({ limit: 100, bbox: [4.7, 52.2, 5.1, 52.5] });
console.log(`${fc.features.length} locations`);
