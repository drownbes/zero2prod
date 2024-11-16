use actix_web::{web, App, HttpRequest, HttpResponse, HttpServer, Result};
use tracing_actix_web::TracingLogger;
use tracing_log::LogTracer;
use tracing_subscriber::fmt;
use tracing_subscriber::fmt::format::FmtSpan;
use tracing_subscriber::EnvFilter;
use zero2prod::email_client::POSTMARK_SERVER_TOKEN;

//TODO: need to figure out if it is possible to reuse defenition from main project
// some problems with deserialise lifetimes
#[derive(serde::Deserialize, Debug)]
#[serde(rename_all = "PascalCase")]
#[allow(dead_code)]
pub struct SendEmailRequest {
    from: String,
    to: String,
    subject: String,
    html_body: String,
    text_body: String,
}

#[tracing::instrument]
async fn email(
    req: HttpRequest,
    req_body: web::Json<SendEmailRequest>,
    token: web::Data<Token>,
) -> Result<HttpResponse, actix_web::Error> {
    let headers = req.headers();
    let header_ok = headers.get(POSTMARK_SERVER_TOKEN).map(|x| x.eq(&token.0));

    match header_ok {
        Some(true) => Ok(HttpResponse::Ok().finish()),
        Some(false) => Ok(HttpResponse::Unauthorized().finish()),
        _ => Err(actix_web::error::ErrorBadRequest("hehe")),
    }
}

#[derive(Debug)]
struct Token(String);

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    LogTracer::init().expect("Failed to set logger");
    let port = std::env::var("PORT")
        .map(|port| port.parse())
        .expect("No PORT env variable have been provided!")
        .expect("Cannot parse port");

    let token: String = std::env::var("POSTMARK_SERVER_TOKEN")
        .expect("No POSTMARK_SERVER_TOKEN env variable have been provided!");
    let token = web::Data::new(Token(token));
    let subscriber = fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .with_span_events(FmtSpan::NEW | FmtSpan::CLOSE)
        .with_target(false)
        .finish();

    tracing::subscriber::set_global_default(subscriber).unwrap();

    HttpServer::new(move || {
        App::new()
            .wrap(TracingLogger::default())
            .route("/email", web::post().to(email))
            .app_data(token.clone())
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}
