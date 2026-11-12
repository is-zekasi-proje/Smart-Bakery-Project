import json
import os

import requests
import streamlit as st
import streamlit.components.v1 as components
from dotenv import load_dotenv

load_dotenv()

st.set_page_config(page_title="SmartBakery 360", layout="wide")

SUPERSET_URL = "http://localhost:8088"
SUPERSET_EMBEDDED_ID = os.environ.get("SUPERSET_EMBEDDED_ID", "").strip()
SUPERSET_SERVICE_USER = os.environ["SUPERSET_SERVICE_USER"]
SUPERSET_SERVICE_PASSWORD = os.environ["SUPERSET_SERVICE_PASSWORD"]

if not SUPERSET_EMBEDDED_ID:
    raise RuntimeError("SUPERSET_EMBEDDED_ID is required in the local .env file.")


def _check_response(response, operation):
    if not response.ok:
        raise RuntimeError(f"{operation} failed (HTTP {response.status_code}).")


@st.cache_data(ttl=240, show_spinner=False)
def get_service_access_token():
    response = requests.post(
        f"{SUPERSET_URL}/api/v1/security/login",
        json={
            "username": SUPERSET_SERVICE_USER,
            "password": SUPERSET_SERVICE_PASSWORD,
            "provider": "db",
            "refresh": True,
        },
        timeout=20,
    )
    _check_response(response, "Superset service login")
    return response.json()["access_token"]


@st.cache_data(ttl=180, show_spinner=False)
def get_guest_token():
    access_token = get_service_access_token()
    session = requests.Session()
    authorization = {"Authorization": f"Bearer {access_token}"}

    csrf_response = session.get(
        f"{SUPERSET_URL}/api/v1/security/csrf_token/",
        headers=authorization,
        timeout=20,
    )
    _check_response(csrf_response, "Superset CSRF request")
    csrf_token = csrf_response.json()["result"]

    response = session.post(
        f"{SUPERSET_URL}/api/v1/security/guest_token/",
        json={
            "user": {
                "username": "streamlit_guest",
                "first_name": "Guest",
                "last_name": "Viewer",
            },
            "resources": [{"type": "dashboard", "id": SUPERSET_EMBEDDED_ID}],
            "rls": [],
        },
        headers={
            **authorization,
            "X-CSRFToken": csrf_token,
            "Referer": f"{SUPERSET_URL}/",
        },
        timeout=20,
    )
    _check_response(response, "Superset guest-token request")
    return response.json()["token"]


st.markdown(
    """
    <style>
    header,
    [data-testid="stHeader"],
    [data-testid="stToolbar"],
    [data-testid="stDeployButton"],
    #MainMenu,
    footer {
        display: none !important;
    }

    html,
    body,
    [data-testid="stAppViewContainer"],
    [data-testid="stMain"],
    section.main {
        overflow: hidden !important;
        height: 100vh !important;
    }

    [data-testid="stAppViewBlockContainer"],
    [data-testid="stMainBlockContainer"],
    .block-container {
        max-width: 100% !important;
        padding: 0 !important;
        margin: 0 !important;
    }

    iframe {
        height: calc(100vh - 2px) !important;
        width: 100% !important;
        border: 0 !important;
        display: block;
    }
    </style>
    """,
    unsafe_allow_html=True,
)


@st.fragment(run_every=240)
def render_dashboard():
    guest_token = get_guest_token()
    components.html(
        f"""
        <style>
        html, body, #superset-dashboard {{
            width: 100%;
            height: 100%;
            margin: 0;
            overflow: hidden;
        }}

        #superset-dashboard iframe {{
            width: 100% !important;
            height: calc(100vh - 2px) !important;
            border: 0 !important;
            display: block;
        }}
        </style>
        <div id="superset-dashboard"></div>
        <script src="https://unpkg.com/@superset-ui/embedded-sdk@0.4.0"></script>
        <script>
        supersetEmbeddedSdk.embedDashboard({{
            id: {json.dumps(SUPERSET_EMBEDDED_ID)},
            supersetDomain: {json.dumps(SUPERSET_URL)},
            mountPoint: document.getElementById("superset-dashboard"),
            fetchGuestToken: () => Promise.resolve({json.dumps(guest_token)}),
            dashboardUiConfig: {{
                hideTitle: true,
                hideChartControls: true,
                hideTab: false
            }}
        }});
        </script>
        """,
        height=800,
        scrolling=False,
    )


render_dashboard()
