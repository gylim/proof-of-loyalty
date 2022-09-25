import React, { useEffect, useState, useContext } from "react";
import { Button, Modal, Form, Row, Col } from 'react-bootstrap';
import { useForm, useFieldArray } from "react-hook-form";
// import { Framework } from "@superfluid-finance/sdk-core";
import { ethers, utils } from "ethers";
import { submitApiCall } from "../helpers/apiController";

export default function ParticipateProject(props) {

    const joinProject = async (data) => {
        console.log("create Project payload", data);
    }

    const verifyTwitter = async () => {

    }

    return (
        <>
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
