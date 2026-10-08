from flask import Flask, jsonify
import os
import socket
import psycopg2

app = Flask(__name__)


def get_db_connection():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        port=5432,
        connect_timeout=3,
        sslmode="disable"
    )


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/api/status")
def status():
    try:
        with get_db_connection() as connection:
            with connection.cursor() as cursor:

                # Record this visit
                cursor.execute(
                    "INSERT INTO visits DEFAULT VALUES;"
                )

                # Get total number of visits
                cursor.execute(
                    "SELECT COUNT(*) FROM visits;"
                )

                total_visits = cursor.fetchone()[0]

        return jsonify(
            application="online",
            database="connected",
            server=socket.gethostname(),
            total_visits=total_visits
        ), 200

    except Exception as error:
        print(f"Database connection failed: {error}", flush=True)

        return jsonify(
            application="online",
            database="disconnected",
            server=socket.gethostname(),
            total_visits=None
        ), 503


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000
    )