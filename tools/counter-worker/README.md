# Visit counter for the book

A small, self-owned visit counter. It runs as a free Cloudflare Worker with a D1
database, and stores only page names and counts. It keeps no IP addresses, no
cookies and no personal data.

## What it does

- Every page of the book sends its own path once per browser session.
- The Worker adds one to that page's count.
- The welcome page shows a badge with the total.
- `/stats` lists the counts of every page, so you can see which chapters are read most.

## One-time setup (about 15 minutes, all in the browser)

1. **Create a free Cloudflare account** at https://dash.cloudflare.com/sign-up.
2. **Create the database.** In the dashboard, open *Storage & Databases*, then *D1*, then *Create database*. Name it `book-counter`.
3. **Create the table.** Open the database, go to its *Console* tab, paste this and run it.

   ```sql
   CREATE TABLE IF NOT EXISTS counts (page TEXT PRIMARY KEY, n INTEGER NOT NULL DEFAULT 0);
   ```

4. **Create the Worker.** Open *Workers & Pages*, then *Create*, then *Create Worker*. Name it `book-counter` and deploy the default "Hello World".
5. **Paste the code.** Click *Edit code*, replace everything with the contents of `worker.js` in this folder, and click *Deploy*.
6. **Connect the database.** In the Worker's *Settings*, open *Bindings*, add a *D1 database* binding with the variable name `DB`, and choose `book-counter`. Deploy again.
7. **Note the address.** It looks like `https://book-counter.<your-subdomain>.workers.dev`. Opening it should show "R for Audit Analytics visit counter".
8. **Tell the book.** In `counter.html` at the root of the book folder, put that address in `COUNTER_URL`, re-render, and publish.

## Checking it

- `https://book-counter.<your-subdomain>.workers.dev/badge.svg` shows the badge.
- `https://book-counter.<your-subdomain>.workers.dev/stats` shows page-wise counts.

## Limits and notes

- The free plan allows 100,000 requests a day and 100,000 rows written a day to D1, far more than the book needs.
- Counts are approximate. A visitor who blocks scripts is not counted, and opening the book in a new browser session counts again.
- To start the count again, run `DELETE FROM counts;` in the D1 console.
