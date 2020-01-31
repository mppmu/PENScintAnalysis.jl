#!/usr/bin/env daqcore-scala-fadc

// :paste run-pen-pmt.scala

import scala.async.Async.{async, await}
import scala.concurrent.{Future, Promise}, scala.concurrent.duration._
import akka.actor.{Cancellable}
import daqcore.actors._, daqcore.io._, daqcore.devices._, daqcore.util._, daqcore.data._, daqcore.defaults._
import daqcore.util.fileops._

import SIS3316.dataTypes._
import SIS3316.SIS3316Impl._

def exit() = { daqcoreSystem.shutdown(); daqcoreSystem.awaitTermination(); sys.exit(0); }

object logger extends Logging
logger.info("Ready")

val outputBasename = "test"
val measurementTime = 10

//if (args.size != 3) throw new RuntimeException("Invalid number of command line arguments")
//val outputBasename= args(0)
//val measurementTime= args(1).toInt
//val trigger= args(2).toInt

val adc = SIS3316("vme-sis3316://gelab-fadc08", "adc")

println(s"ADC identity: ${adc.identity.get}, serial number ${adc.serNo.get}")
println(s"ADC temperature: ${adc.internalTemperature.get} °C")


//val pmt1 = Ch(1)
//val pmt2 = Ch(2)
//val pmt3 = Ch(3)
//val pmt4 = Ch(4)
//val pmt5 = Ch(5)
//val pmt6 = Ch(6)
//val pmtChannels = Ch(pmt1, pmt2, pmt3, pmt4, pmt5, pmt6)
//Channels START













//Channels END

val allChannels = pmtChannels


def configureADC_allch(): Unit = {
  adc.trigger_extern_enabled_set(allChannels --> false)
  adc.trigger_intern_enabled_set(allChannels --> false)
  adc.event_format_set(allChannels --> EventFormat())
  adc.bank_fill_threshold_stop_set(allChannels --> false)
  adc.getSync().get
}


def configureADC_allPMT(): Unit = {
  adc.trigger_intern_enabled_set(pmt5 --> true)
  adc.trigger_intern_feedback_set(pmt5 --> true)
  adc.trigger_extern_enabled_set(pmtChannels --> true)
  adc.input_invert_set(pmtChannels --> true)

  val peakTime = 2
  val gapTime  = 2
  val nPreTrig = 192
  val nSamples =  256
  // Threshold START
  val threshold_1 = 55
  val trigger_pmt1 = pmt1
  adc.trigger_threshold_set(trigger_pmt1 --> trigger)

































  // Threshold STOP


  adc.trigger_gate_window_length_set(pmtChannels --> nSamples)


  adc.trigger_cfd_set(pmtChannels --> CfdCtrl.CDF50Percent)
  adc.trigger_peakTime_set(pmtChannels --> peakTime)
  adc.trigger_gapTime_set(pmtChannels --> gapTime)

  adc.acc_start_set(1)(pmtChannels --> 0).get
  adc.acc_length_set(1)(pmtChannels --> peakTime).get

  adc.acc_start_set(2)(pmtChannels --> (peakTime + gapTime)).get
  adc.acc_length_set(2)(pmtChannels --> peakTime).get

  adc.acc_start_set(3)(pmtChannels --> (peakTime + gapTime - 10)).get
  adc.acc_length_set(3)(pmtChannels --> 10).get

  adc.acc_start_set(4)(pmtChannels --> (peakTime + gapTime)).get
  adc.acc_length_set(4)(pmtChannels --> 10).get

  adc.event_format_set(pmtChannels -->
    EventFormat(
      save_maw_values = None,
      save_energy = true,
      save_ft_maw = true,
      save_acc_78 = false,
      save_ph_acc16 = true,
      nSamples = nSamples,
      nMAWValues = nSamples
    )
  )

  adc.nsamples_pretrig_set(pmtChannels --> nPreTrig)
  adc.nmaw_pretrig_set(pmtChannels --> nPreTrig)

  adc.getSync().get
  val rawEventDataSize = adc.event_format_get(pmtChannels).get vMap {_.rawEventDataSize}
  adc.bank_fill_threshold_nbytes_set(rawEventDataSize vMap {400 * _})
  adc.getSync().get
}


def configureADCs(): Unit = {
  configureADC_allch()
  configureADC_allPMT()
}


def printStatus() {
  println(s"Buffer count: ${adc.buffer_counter_get.get}")
  println(s"ADC temperature: ${adc.internalTemperature.get} Â°C")
}

configureADCs()
printStatus()


adc.raw_output_file_basename_set(s"${outputBasename}")

def start() = {
  adc.startCapture()
}

def stop() = {
  adc.stopCapture()
}

import java.io.File
def getListOfFiles(dir: File, extensions: List[String]): List[File] = {
    dir.listFiles.filter(_.isFile).toList.filter { file =>
        extensions.exists(file.getName.endsWith(_))
    }
}

logger.info("Output basename: $outputBasename")
logger.info("Measurement time: $measurementTime s")


println(s"Output basename: ${outputBasename}")
println(s"Measuring for ${measurementTime} s")

start()
Thread.sleep(measurementTime*1000)
stop()

// now, wait till conversion from .tmp to .dat file has been completed.
val files = getListOfFiles(new File("."), List("tmp")) // files in current directory with extension ".tmp"
var n_tmp_files = files.length
while(n_tmp_files != 0){
  Thread.sleep(1000)
  val files = getListOfFiles(new File("."), List("tmp")) // files in current directory with extension ".tmp"
  n_tmp_files = files.length
}
Thread.sleep(1000) // sleep 1s for security

exit()
