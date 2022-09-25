// import { React, useEffect, useState } from "react";
import React, { useEffect, useState, useContext } from "react";
import { Button, Modal, Form, Row, Col } from 'react-bootstrap';
import { useForm, useFieldArray } from "react-hook-form";
// import { Framework } from "@superfluid-finance/sdk-core";
import { ethers, utils } from "ethers";


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
      oracleReward: 0.1,
      oracleLiveness: 90

    }
  });

  useEffect(() => {
    console.log("my Pol Contract", props.PoLContract);
  });

  const onSubmit = async (data) => {
    console.log("create Project payload", data);

    // TODO: Call CommenceCampaign API
    // const provider = new ethers.providers.JsonRpcProvider(
    //   // process.env.GOERLI_URL
    // )
    // debugger;
    // const sf = await Framework.create({
    //   networkName: "goerli",
    //   provider
    // });
    // const lyt = await sf.loadSuperToken("0x0649cEc7f0EE517C7b422689cB9375b18B4AD3FA");
    // const res = await props.polContract.commenceCampaign(
    //   lyt,
    //   ethers.utils.parseEther(data.amount.toString()),
    //   ethers.utils.parseEther(data.maxAmt.toString()),
    //   data.startDate,
    //   data.endDate, // convert to s
    //   data.duration, // s
    //   //_oracleBond, ="0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
    //   _oracleReward,
    //   _oracleLiveness
    // )
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