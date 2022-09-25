import React, { useEffect, useState, useContext } from "react";
import { Button, Modal, Form, Row, Col } from 'react-bootstrap';
import { useForm, useFieldArray } from "react-hook-form";
// import { Framework } from "@superfluid-finance/sdk-core";
import { ethers, utils } from "ethers";
import { submitApiCall } from "../helpers/apiController";

export default function ParticipateProject(props) {
    return (
        <>
            Participate Project
            <Modal
                show={showModal}
                onHide={handleClose}
                size="md"
                aria-labelledby="contained-modal-title-vcenter"
                centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Create Project
                    </Modal.Title>
                </Modal.Header>
                <Form onSubmit={handleSubmit(onSubmit)}>
                    <Modal.Body>
                        <Row>
                            <Form.Group as={Col}>
                                <Form.Label>Project name</Form.Label>
                                <Form.Control {...register("projectName", { required: true })} type="string" placeholder="" />
                            </Form.Group>
                        </Row>
                        <Row>
                            <Form.Group as={Col}>
                                <Form.Label>Twitter Account to Follow</Form.Label>
                                <Form.Control {...register("twitterID", { required: true })} type="number" placeholder="@Elonmusk" />
                            </Form.Group>
                        </Row>
                        <Row>
                            <Form.Group as={Col}>
                                <Form.Label>Project Budget</Form.Label>
                                <Form.Control {...register("amount", { required: true })} type="number" placeholder="in ETH" />
                            </Form.Group>
                        </Row>
                        <Row>
                            <Form.Group as={Col}>
                                <Form.Label>Reward per Participant</Form.Label>
                                <Form.Control {...register("maxAmt", { required: true })} defaultValue='' type="number" placeholder="in ETH" />
                            </Form.Group>
                        </Row>
                        <Row>
                            <Form.Group as={Col}>
                                <Form.Label>Vesting Duration (in days)</Form.Label>
                                <Form.Control {...register("duration", { required: true })} defaultValue='' type="number" placeholder="" />
                            </Form.Group>
                        </Row>
                        <Row>
                            <Form.Group as={Col}>
                                <Form.Label>Campaign Commence Date</Form.Label>
                                <Form.Control {...register("startDate", { required: true })} defaultValue='' type="date" placeholder="" />
                            </Form.Group>
                            <Form.Group as={Col}>
                                <Form.Label>Campaign End Date</Form.Label>
                                <Form.Control {...register("endDate", { required: true })} defaultValue='' type="date" placeholder="" />
                            </Form.Group>
                        </Row>
                        <Row>
                            <h5>Social Delegation (Powered by UMA)</h5>
                            <Form.Group as={Col}>
                                <Form.Label>Task Reward</Form.Label>
                                <Form.Control {...register("oracleReward", { required: true })} defaultValue='' type="number" placeholder="" />
                            </Form.Group>
                            <Form.Group as={Col}>
                                <Form.Label>Task Duration</Form.Label>
                                <Form.Control {...register("oracleLiveness", { required: true })} defaultValue='' type="number" placeholder="" />
                            </Form.Group>
                        </Row>

                    </Modal.Body>
                    <Modal.Footer className="text-center">
                        <Button variant="dark" type="submit" size="lg" >Create</Button>
                    </Modal.Footer>
                    {/* <pre>
        {JSON.stringify(fields, null, 3)}
    </pre> */}
                </Form>
            </Modal>
        </>
    )
}
