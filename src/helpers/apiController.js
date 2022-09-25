import axios from "axios";

// Default Settings
// axios.defaults.baseURL = process.env.REACT_APP_API_BASE_URL;
axios.defaults.baseURL = 'http://localhost:4000';
axios.defaults.headers.common["Content-Type"] = "application/json"; // for all requests

export const fetchApiCall = async (restUrl, publicKey = "") => {
    const resp = await axios.get(restUrl, {
        headers: {
            PublicKey: publicKey,
        },
    });
    if (resp && resp.status >= 300) {
        // TODO: Handle Errors Later, Show Modal Etc
        const error = await resp.json();
        return {
            error: true,
            msg: error?.message ? error.message : "Back end error",
        };
    }
    return resp.data;
};

export const submitApiCall = async (restUrl, publicKey, body) => {
    const resp = await axios.post(restUrl, body, {
        headers: {
            PublicKey: publicKey,
        },
    });
    if (resp && resp.status >= 300) {
        // TODO: Handle Errors Later, Show Modal Etc
        const error = await resp.json();
        return {
            error: true,
            msg: error?.message ? error.message : "Back end error",
        };
    }
    return resp.data;
};
