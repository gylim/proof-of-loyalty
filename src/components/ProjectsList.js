import React, { useEffect, useState } from 'react';
import { Button } from 'react-bootstrap';
import Card from 'react-bootstrap/Card';
import Badge from 'react-bootstrap/Badge';
import ParticipateProject from './ParticipateProject';
import { Twitter } from 'react-bootstrap-icons';



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

            // <div direction="horizontal" gap={20}>
            <div className='dashboardListing' key={x._id}>
                <Card style={{ width: '20rem', borderRadius: '2rem' }}>
                    {/* <Card.Img src="https://picsum.photos/seed/picsum/400/300" alt="Card image" /> */}
                    {/* <Card.ImgOverlay> */}



                    <Card.Body>
                        <Card.Title>{x.projectName}</Card.Title>
                        <Card.Subtitle className="mb-2 text-muted"><Twitter />Follow {x.twitterID}</Card.Subtitle>
                        <Card.Text>
                            <Badge pill bg="dark">
                                {x.maxAmt} ETH
                            </Badge>{' '}
                        </Card.Text>
                        <Button onClick={() => { setModal(x) }}>Participate</Button>
                    </Card.Body>
                    {/* </Card.ImgOverlay> */}
                </Card>
            </div>
            // </div >
        )
    })
    return (
        <>
            <div className='container'>{projects}</div>
            <ParticipateProject showModal={showModal} project={modalData} closeModal={closeModal} />
        </>

    )
}
