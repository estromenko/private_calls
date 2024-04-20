export function createPeerConnection() {
  const configuration = { "iceServers": [{ "urls": "stun:stun.l.google.com:19302" }] }
  const peerConnection = new RTCPeerConnection(configuration)
  return peerConnection
}

export async function playOwnVideo(stream) {
  const localVideo = document.querySelector("#local-video")
  localVideo.srcObject = stream
  localVideo.setAttribute("data-stream-id", stream.id)
  await localVideo.play()
}

export async function getMediaStream() {
  const mediaConstrains = { video: true, audio: true }
  const stream = await navigator.mediaDevices.getUserMedia(mediaConstrains)
  return stream
}

export async function makeCall(liveSocket, peerConnection, stream) {
  stream.getTracks().forEach((track) => {
    peerConnection.addTrack(track, stream)
  })

  const offer = await peerConnection.createOffer()
  await peerConnection.setLocalDescription(offer)

  liveSocket.pushEvent("rtc_message", { message: { offer } })
}

export async function leaveCall(liveSocket, peerConnection, stream) {
  liveSocket.pushEvent("rtc_close", { streamId: stream.id })

  window.handledStreams?.clear()

  stream.getTracks().forEach((track) => {
    track.stop()
  })
}

export async function playRemoteVideos(liveSocket, peerConnection) {
  window.handledStreams = new Set()

  peerConnection.addEventListener("track", async (event) => {
    const stream = event.streams[0]
    if (window.handledStreams.has(stream.id)) {
      return
    }
    window.handledStreams.add(stream.id)

    const remoteVideo = document.createElement("video")
    remoteVideo.setAttribute("data-stream-id", stream.id)
    remoteVideo.srcObject = stream

    const videos = document.querySelector("#videos")
    videos.append(remoteVideo)

    await remoteVideo.play()
  })

  window.addEventListener("phx:rtc_message", async (event) => {
    if (event.detail.answer) {
      const remoteDesc = new RTCSessionDescription(event.detail.answer)
      await peerConnection.setRemoteDescription(remoteDesc)
    }

    if (event.detail.candidate) {
      await peerConnection.addIceCandidate(event.detail.candidate)
    }

    if (event.detail.offer) {
      const remoteDesc = new RTCSessionDescription(event.detail.offer)
      peerConnection.setRemoteDescription(remoteDesc)
      const answer = await peerConnection.createAnswer()
      await peerConnection.setLocalDescription(answer)
      liveSocket.pushEvent("rtc_message", { message: { answer } })
    }
  })

  window.addEventListener("phx:rtc_close", async (event) => {
    const streamId = event.detail.stream_id
    const video = document.querySelector(`[data-stream-id="${streamId}"]`)
    video?.remove()
  })

  peerConnection.addEventListener("icecandidate", (event) => {
    if (event.candidate) {
      liveSocket.pushEvent("rtc_message", { message: { candidate: event.candidate } })
    }
  })
}
