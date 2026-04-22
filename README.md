# kopokeitumetse.github.io

Personal portfolio and technical blog for **Kopo Keitumetse** — ICT Applications Support Specialist based in Gaborone, Botswana. Built as a static GitHub Pages site with a terminal/hacker aesthetic.

Live site: [kopokeitumetse.github.io](https://kopokeitumetse.github.io)

---

## About

Kopo works in enterprise IT support with a focus on ERP systems (Sage 50c), Microsoft 365 administration, ITSM, and infrastructure. This site serves as a portfolio, blog, and professional reference — covering real work experience, personal projects, and technical write-ups drawn from day-to-day IT practice.

---

## Pages

| Page | Description |
|---|---|
| `index.html` | Home — terminal split-panel layout with featured projects and recent blog logs |
| `experience.html` | Work history, skills timeline, and certifications |
| `project.html` | Project showcase — Equipment Management System, HR Document Portal |
| `blog.html` | Blog archive with `ls -la` style file listing |

### Blog Posts

| File | Topic |
|---|---|
| `blog_post.html` | How I Validate Client Data Before a Sage 50c Go-Live |
| `blog_post_exchange.html` | SLA Monitoring with SQL: Building Monthly IT Reports |
| `blog_post_ad_automation.html` | Training 80+ Users on Sage 50c: What Actually Works |
| `blog_post_ems.html` | Building an Asset Tracker with FastAPI and SQL |
| `blog_post_rbac.html` | Getting AWS Cloud Practitioner Certified: My Study Approach |
| `blog_post_duplicates.html` | Duplicate File Scanner (PowerShell) |

### Downloadable Script

`Find-DuplicateFiles.ps1` — PowerShell script that scans a Windows machine for duplicate files using a two-phase size pre-filter + SHA256 hash approach, then exports a grouped CSV report. Read-only — never deletes files.

---

## Stack

- **HTML5** — no build step, no framework
- **Tailwind CSS** (CDN) — utility-first styling with a custom dark theme
- **Vanilla JavaScript** — Matrix rain canvas animation, typewriter effect
- **Google Fonts** — Space Grotesk, Fira Code, Outfit

### Theme

```
Background : #0D1117
Surface    : #161B22
Primary    : #06f943  (terminal green)
Accent     : #58A6FF  (blue)
Text       : #C9D1D9
Border     : #30363D
```

---

## Running Locally

No build tools required. Open any `.html` file directly in a browser, or serve the directory:

```bash
# Python
python -m http.server 8080

# Node (npx)
npx serve .
```

Then visit `http://localhost:8080`.

---

## Deployment

Deployed via **GitHub Pages** from the `main` branch root. `index.html` is the entry point.

Any push to `main` triggers an automatic redeploy.

---

## Contact

- Email: [kkeitumetse09@gmail.com](mailto:kkeitumetse09@gmail.com)
- GitHub: [github.com/kopokeitumetse](https://github.com/kopokeitumetse)
- CV: [Kopo_Keitumetse_CV.pdf](./Kopo_Keitumetse_CV.pdf)
