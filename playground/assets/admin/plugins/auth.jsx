// Lane `auth`: /admin/login and /admin/account pages (cookie-session auth via /admin/api/auth/*).
import { Page as LoginPage, AccountPage } from "../auth/pages.jsx";

export default {
  id: "auth",
  pages: [
    { path: "login", label: "Login", Page: LoginPage },
    { path: "account", label: "Account", Page: AccountPage },
  ],
  tabs: [],
};
