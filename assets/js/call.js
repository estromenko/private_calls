const iceServers = [
  { urls: 'stun:freeturn.net:5349' },
  { urls: 'turns:freeturn.tel:5349', username: 'free', credential: 'free' },
]

export function createPeerConnection(liveSocket, userId) {
  const configuration = { "iceServers": iceServers }
  const peerConnection = new RTCPeerConnection(configuration)

  window.stream.getTracks().forEach((track) => {
    peerConnection.addTrack(track, window.stream)
  })

  peerConnection.addEventListener("track", async (event) => {
    const stream = event.streams[0]
    const remoteVideo = document.querySelector(`video[data-id="${userId}"]`)
    remoteVideo.srcObject = stream

    await remoteVideo.play()
  })

  peerConnection.addEventListener("icecandidate", (event) => {
    if (event.candidate) {
      liveSocket.pushEvent("rtc_message", {
        message: { candidate: event.candidate, fromUserId: window.localUserId, toUserId: userId },
      })
    }
  })

  return peerConnection
}

export async function playOwnVideo() {
  const streamWithoutVoice = await navigator.mediaDevices.getUserMedia({ video: true })
  const localVideo = document.querySelector("#local-video")
  localVideo.srcObject = streamWithoutVoice
  await localVideo.play()
}

export async function makeCall(liveSocket, userId) {
  const peerConnection = window.peers[userId]
  const offer = await peerConnection.createOffer()
  await peerConnection.setLocalDescription(offer)

  liveSocket.pushEvent("rtc_message", {
    message: {
      offer, fromUserId: window.localUserId, toUserId: userId,
    },
  })
}

export async function leaveCall(liveSocket) {
  liveSocket.pushEvent("rtc_close", { userId: window.localUserId })

  window.stream.getTracks().forEach((track) => {
    track.stop()
  })

  window.peers = {}
}

export async function playRemoteVideos(liveSocket) {
  window.addEventListener("phx:rtc_message", async (event) => {
    let peerConnection = window.peers[event.detail.fromUserId]
    if (!peerConnection) {
      peerConnection = createPeerConnection(liveSocket, event.detail.fromUserId)
      window.peers[event.detail.fromUserId] = peerConnection
    }

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
      liveSocket.pushEvent("rtc_message", {
        message: { answer, fromUserId: window.localUserId, toUserId: event.detail.fromUserId },
      })
    }
  })

  window.addEventListener("phx:rtc_close", async (event) => {
    window.peers[event.detail.user_id]?.close()
    window.peers[event.detail.user_id] = null
  })
}
