const express = require('express');
const axios = require('axios');

const app = express();
const port = 3000;

const goServiceUrl = process.env.GO_SERVICE_URL || 'http://localhost:8080';

app.get('/', async (req, res) => {
  try {
    const response = await axios.get(`${goServiceUrl}/ping`);
    res.send(`Response from Go service: ${response.data}`);
  } catch (error) {
    res.status(500).send('Error connecting to Go service');
  }
});

app.listen(port, () => {
  console.log(`Node service listening at http://localhost:${port}`);
});
