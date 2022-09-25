import React, { useEffect, useState } from 'react';
import { Button } from 'react-bootstrap';
import Card from 'react-bootstrap/Card';
import Stack from 'react-bootstrap/Stack';
import ParticipateProject from './ParticipateProject';


export default function ProjectsList(props) {
    const [showModal, setShowModal] = useState(false);
    const [modalData, setModalData] = useState(false);

    function setModal(obj) {
        setShowModal(true);
        setModalData(obj)
    }
    function closeModal() {
        setShowModal(false);
        setModalData({})
    }

    let projects = props?.projectsList?.map(x => {
        return (
            <Stack gap={3} key={x._id}>
                <Card style={{ width: '18rem' }}>
                    <Card.Body>
                        <Card.Title>{x.projectName}</Card.Title>
                        <Card.Subtitle className="mb-2 text-muted">Follow {x.twitterID}</Card.Subtitle>
                        <Card.Text>
                            Reward: {x.maxAmt} ETH
                        </Card.Text>
                        <Button onClick={() => { setModal(x) }}>Participate</Button>
                    </Card.Body>
                </Card>
            </Stack >
        )
    })
    return (
        <>
            <div className='container'>{projects}ds</div>
            <ParticipateProject showModal={showModal} project={modalData} closeModal={closeModal} />
        </>
    )
}
