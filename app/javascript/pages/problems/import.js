import JSZip from "jszip";
import { ajaxUploadFunc } from "../../helpers/ajax_upload";


function zipProgress(progress) {
    $("#progress-inner-bar").width( progress.percent + "%");
    $("#progress-text").text("Compressing files: " + (progress.percent).toFixed(2) + "%");
}

function importOnProgress(finished,evt) {
    if( finished ) {
        $("#progress-inner-bar").width("100%");
        $("#progress-text").text("Processing files...");
    }
    else {
        $("#progress-inner-bar").width((evt.loaded / evt.total) * 100 + "%");
        $("#progress-text").text(renderUploadProgress(evt));
    }
}

function importOnAbort() {
    $("#progress-fade").removeClass("in");
    $("#progress-inner-bar").width("0%");
    $("#progress-text").text("Upload aborted");
    $("#submit-button").removeAttr("disabled");
}

function importAlways(nxhr,status) {
    document.head.appendChild(MathJax.svgStylesheet());
    MathJax.typesetPromise();
    if( status != "success")
        initProblemImport();
}

function getZipFile(jsonFile) {
    let zipFile = new JSZip();

    zipFile.file(jsonFile.name, jsonFile, {compression: "DEFLATE"});
    return zipFile;
}

async function getAvailableLanguages(zipFile) {
    let Language = new Set();
    const zip = await JSZip.loadAsync(zipFile);;
    const pattern = new RegExp("^statement-sections\/(chinese|english)\/");
    zip.forEach( (relativePath, zipEntry) => {
        const match = pattern.exec(relativePath);
        if( match ) {
            const language = match[1];
            Language.add(language);
        }
    });
    return Language;
}

function isFileZip(file) {
    return file.type == "application/zip";
}
function isFileJson(file) {
    return file.name.endsWith(".json") || file.name.endsWith(".zjson");
}

function assert(condition, message) {
    if( !condition ) {
        alert(message);
        location.reload();
    }
}

function updateFileChecker(event) {
    if( $("#type-select").val() == "zjson" ) {
        assert( isFileJson($("#file")[0].files[0]), "Invalid file type, please upload a json file" );
    }
    else if( $("#type-select").val() == "poloygon" ) {
        assert( isFileZip($("#file")[0].files[0]), "Invalid file type, please upload a zip file");
        getAvailableLanguages($("#file")[0].files[0]).then( (Language) => {
            assert( Language.size > 0, "Invalid Polygon file, which has no language directory(chinese, english)" );

            $("#language-select").empty();

            Language.forEach( (lang) => {
                $("#language-select").append(`<option value="${lang}">${lang}</option>`);
            });
        });
    }
}


function updateUploadMethod(event) {
    $("#file").val("");
    assert( ['zjson', 'poloygon'].includes(event.target.value), "Invalid upload method");
    if( event.target.value == "zjson" ) {
        $("#language-select-group").fadeOut();
    }
    else if( event.target.value == "poloygon" ) {
        $("#language-select-group").fadeIn();
    }
}

export function initProblemImport () {
    $("#type-select").on("change", updateUploadMethod);
    $("#file").on("change", updateFileChecker);

    $("#problem-form").on("submit", function(event) {
        event.preventDefault();

        assert( $("#file")[0].files.length > 0, "Please select a file" );
        // the file size should not bigger that 5GiB
        const MAX_SIZE = 5 * 1024 * 1024 * 1024;
        assert( $("#file")[0].files[0].size < MAX_SIZE, "File size should not bigger than 5GiB" );

        let url = $(this).attr("action");

        $("#progress-fade").addClass("in");

        if( $("#type-select").val() == "zjson") {
            let zipFile = getZipFile($("#file")[0].files[0]);
            let formData = new FormData(this);
            formData.delete("problem[file]");

            zipFile.generateAsync({type: "blob",streamFiles: true}, function updateCallback(progress) {
                zipProgress(progress);
            }).then( (zippedFile) => {
                formData.append("problem[file]", zippedFile, "zjson.zip");
                ajaxUploadFunc()(url, formData, importOnProgress, importOnAbort, importAlways)
            });
        }
        else if( $("#type-select").val() == "poloygon") {
            getAvailableLanguages($("#file")[0].files[0]);
            ajaxUploadFunc()(url, new FormData(this), importOnProgress, importOnAbort,importAlways);
        }
    });
}