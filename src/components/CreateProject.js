// import { React, useEffect, useState } from "react";
import React, { useEffect, useState, useContext } from "react";
import { Button, Modal, Form, Row, Col } from 'react-bootstrap';
import { useForm, useFieldArray } from "react-hook-form";
import { utils } from "ethers";

// ISuperToken _token, uint _amount, uint _maxAmt,
//   uint _startDate, uint _endDate, uint _duration,
//     IERC20 _oracleBond, uint _oracleReward, uint _oracleLiveness

export default function CreateProject(props) {
  const [inputs, setInputs] = useState({});
  const [showModal, setModal] = useState(false);
  const { register, handleSubmit, watch, formState: { errors } } = useForm({
    defaultValues: {
      amount: 100,
      maxAmt: 1,
      startDate: Date.now(),
      endDate: null,
      duration: 90,
    }
  });

  useEffect(() => {
    console.log("my Pol Contract", props.PoLContract);
  });

  const onSubmit = async (data) => {
    console.log("create Project payload", data);
  };

  function toggleModal() {
    setModal(true);
  }
  function handleClose() {
    setModal(false);
  }

  return (
    <>
      <Button onClick={toggleModal}>createProject</Button>
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