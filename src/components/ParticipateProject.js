import React, { useEffect, useState, useContext } from "react";
import { Button, Modal, Form, Row, Col } from 'react-bootstrap';
import { useForm, useFieldArray } from "react-hook-form";
// import { Framework } from "@superfluid-finance/sdk-core";
import { ethers, utils } from "ethers";
import { submitApiCall } from "../helpers/apiController";

export default function ParticipateProject(props) {
    const [status, setStatus] = useState()
    const [twitterID, setTwitterID] = useState()

    const joinProject = async (data) => {
        console.log("create Project payload", data);
    }

    const verifyTwitter = async () => {
        // useEffect(() => {
            setStatus("loading")
            fetch(`https://nodeproofofloyalty.herokuapp.com/twitterauth/login`)
                // .then((response) => response.json())
                .then((userinfo) => {
                    console.log("userinfo",userinfo)
                    setTwitterID(userinfo.id)
                    setStatus("success")
                    console.log("userinfo.id",userinfo.id)
                })
                .catch((error) => {
                    console.error(error)
                    setStatus("error")
                })
    
        // }, []);
    }
        if (status === "loading") {
            return <div>Loading...</div>
        }
        if (status === "error") {
            return <div>Not Loading...</div>

    }

    return (
        <>
            Participate Project
            <Modal
                show={props.showModal}
                onHide={() => { props.closeModal() }}
                size="md"
                aria-labelledby="contained-modal-title-vcenter"
                centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Please Follow {props.project.projectName}
                    </Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    <p>I have followed @{props.project.twitterID}</p>
                    <Button onClick={verifyTwitter}> Verify Twitter</Button>
                </Modal.Body>
                <Modal.Footer className="text-center">
                    <Button variant="dark" onClick={joinProject} size="lg" >Lock Me In</Button>
                </Modal.Footer>

            </Modal>
        </>
    )
}
