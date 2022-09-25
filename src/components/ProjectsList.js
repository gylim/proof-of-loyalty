import React from 'react';
import { Button } from 'react-bootstrap';
import Card from 'react-bootstrap/Card';
import Stack from 'react-bootstrap/Stack';




export default function ProjectsList(props) {

    let projects = props?.projectsList?.map(x => {
        return (
            <Stack gap={3}>
                <Card style={{ width: '18rem' }}>
                    <Card.Body>
                        <Card.Title>{x.projectName}</Card.Title>
                        <Card.Subtitle className="mb-2 text-muted">Follow {x.twitterID}</Card.Subtitle>
                        <Card.Text>
                            Some quick example text to build on the card title and make up the
                            bulk of the card's content.
                        </Card.Text>
                        <Button onClick={() => { }}>Participate</Button>
                    </Card.Body>
                </Card>
            </Stack >
        )
    })
    return (
        <div className='container'>{projects}ds</div>
    )
}
