const fs = require('fs');
var o2x = require('object-to-xml');
var format = require('date-format');

module.exports = function (options) {
    // initialize an empty report data
    const customReport = {
        results: {
            violations: 0,
            generated: format('dd MM yyyy hh:mm:ss', new Date()),
            item: [],
            errors: []
        }
    }

    const fileName = options.fileName

    return {
        // add test results to the report
        results(results) {
            customReport.results["item"].push(results)
            customReport.results["item"].violations += results.issues.length;
        },

        // also store errors
        error(error, url) {
            customReport.results["item"].errors.push({ error, url });
        },

        // write to a file
        afterAll() {
            const data = o2x(customReport);//JSON.stringify(customReport);
            return fs.promises.writeFile(fileName, data, 'utf8');
        }
    }
};
