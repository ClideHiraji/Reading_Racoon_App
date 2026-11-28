# Frontend: teacher dashboard and admin portal

The web pages, as Blade templates. Laravel builds them on the server (`config/view.php` points here).

| Folder | Pages |
|---|---|
| `teacher/` | Teacher dashboard: `home` (sections), `section` (class page), `student`, `report` and `report-pdf`, `schedule`, `content/` (books and videos) |
| `admin/` | Admin portal: `dashboard`, `registrations`, `logs`, `privacy`, `content`, `export`, `login` |
| `auth/` | Teacher login, register, "waiting for approval" |
| `layouts/` | The frame around every page: `app` (teacher), `admin` |
| `partials/` | Shared pieces: flash messages, field errors, the style links (`styles`) |
| `errors/` | 403, 404, 419, 429, 500, 503 pages |

Styles and scripts can't live here: Apache serves only `backend/public/`. They are
`public/css/portal.css` and `public/js/portal.js`, shared by teacher and admin.
