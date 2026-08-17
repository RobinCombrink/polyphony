fn main() {
    // 2026-08-17: sqlx's `migrate!` does not itself rebuild when a file under migrations/
    // changes. This line is what makes it; without it, stale migrations compile in silently.
    println!("cargo:rerun-if-changed=migrations");
}
