use std::net::TcpListener;

use sqlx::Connection;
use zero2prod::configurations::get_configuration;
use zero2prod::startup::run;

use sqlx::PgPool;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let configuration = get_configuration().expect("Failed to read configuration");
    let connection_pool = PgPool::connect(&configuration.database.connection_string())
        .await
        .expect("Failed to connect to Postgres.");

    let address = format!("127.0.0.1:{}", configuration.application_port);
    let listener = TcpListener::bind(address).expect("Failed to bind random port");
    let s = run(listener, connection_pool)?;
    s.await
}
