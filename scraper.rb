<?php
require_once 'vendor/autoload.php';
require_once 'vendor/openaustralia/scraperwiki/scraperwiki.php';

use PGuardiario\PGBrowser;
use Sunra\PhpSimple\HtmlDomParser;

date_default_timezone_set('Australia/Sydney');

# Default to 'thisweek', use MORPH_PERIOD to change to 'thismonth' or 'lastmonth' for data recovery
switch(getenv('MORPH_PERIOD')) {
    case 'thismonth' :
        $period = 'thismonth';
        break;
    case 'lastmonth' :
        $period = 'lastmonth';
        break;
    default         :
        $period = 'thisweek';
        break;
}
print "Getting data for `" .$period. "`, changable via MORPH_PERIOD environment\n";

$url_base = "https://da.bundaberg.qld.gov.au/modules/ApplicationMaster/";
$term_url = "https://da.bundaberg.qld.gov.au/modules/common/Default.aspx?page=disclaimer";
$da_page  = $url_base . "default.aspx?page=found&1=" .$period. "&4a=333,322,321,324,323,325&6=F";
$comment_base = "mailto:CEO@bundaberg.qld.gov.au?subject=Development Application Enquiry: ";

# Agreed Terms
$browser = new PGBrowser();
$page = $browser->get($term_url);
$form = $page->form();
if ( empty($form) ) {
    print "Distil networks kicks in..... :-( \n";
    exit(0);
}
$form->set('ctl00$cphContent$ctl00$btnOk', 'Agree');
$page = $form->submit();
sleep(mt_rand(3, 5));

$page = $browser->get($url_base . 'Default.aspx?page=search');
sleep(mt_rand(3, 5));

$page = $browser->get($da_page);
$dom = HtmlDomParser::str_get_html($page->html);

$NumPages = count($dom->find('div[class=rgWrap rgNumPart] a'));
if ($NumPages === 0) {
    $NumPages = 1;
}

for ($i = 1; $i <= $NumPages; $i++) {
    print "Scraping page $i of $NumPages \n";

    # If more than a single page, fetch the page
    if ($i > 1) {
        $form = $page->form();
        sleep(mt_rand(3, 5));
        $page = $form->doPostBack($dom->find('div[class=rgWrap rgNumPart] a', $i-1)->href);
        $dom  = HtmlDomParser::str_get_html($page->html);
    }

    $results = $dom->find("tr[class=rgRow], tr[class=rgAltRow]");
    if ( empty($results) ) {
      print "Distil networks kicks in..... :-( \n";
      exit(0);
    }

    # The usual, look for the data set and if needed, save it
    foreach ($results as $result) {
        # Slow way to transform the date but it works
        $date_received = explode(' ', (trim($result->children(2)->plaintext)), 2);
        $date_received = explode('/', $date_received[0]);
        $date_received = "$date_received[2]-$date_received[1]-$date_received[0]";

        # Prep a bit more, ready to add these to the array
        $tempstr = explode('<br/>', $result->children(3)->innertext);

        # Put all information in an array
        $record = array (
            'council_reference' => trim($result->children(1)->plaintext),
            'address'           => trim(preg_replace('/\s+/', ' ', $tempstr[0]) . ", QLD"),
            'description'       => preg_replace('/\s+/', ' ', $tempstr[1]),
            'info_url'          => $url_base . trim($result->find('a',0)->href),
            'comment_url'       => $comment_base . trim($result->children(1)->plaintext),
            'date_scraped'      => date('Y-m-d'),
            'date_received'     => date('Y-m-d', strtotime($date_received))
        );

        # Check if record exist, if not, INSERT, else do nothing
        $existingRecords = scraperwiki::select("* from data where `council_reference`='" . $record['council_reference'] . "'");
        if (count($existingRecords) == 0) {
            print ("Saving record " . $record['council_reference'] . " - " . $record['address']. "\n");
#            print_r ($record);
            scraperwiki::save(['council_reference'], $record);
        } else {
            print ("Skipping already saved record " . $record['council_reference'] . "\n");
        }
    }
}

?>
